-- Central Sly — fase 1, task 1.01 (SPEC-1-001)
-- Perfis, auditoria, funções de papel e RLS.
-- Compatibilidade: public.perfis.id continua sendo o UUID de auth.users porque
-- as telas e as FKs comerciais existentes dependem dele. user_id é um alias
-- 1:1 sincronizado; criado_em/atualizado_em também convivem com created_at/updated_at.

BEGIN;

-- 1) Completa a tabela de perfis existente sem trocar os IDs usados pelas FKs.
ALTER TABLE public.perfis
  ADD COLUMN IF NOT EXISTS user_id uuid,
  ADD COLUMN IF NOT EXISTS ultimo_acesso_em timestamptz,
  ADD COLUMN IF NOT EXISTS criado_em timestamptz,
  ADD COLUMN IF NOT EXISTS atualizado_em timestamptz;

UPDATE public.perfis
SET user_id = COALESCE(user_id, id),
    criado_em = COALESCE(criado_em, created_at, now()),
    atualizado_em = COALESCE(atualizado_em, updated_at, now())
WHERE user_id IS NULL OR criado_em IS NULL OR atualizado_em IS NULL;

ALTER TABLE public.perfis
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN criado_em SET DEFAULT now(),
  ALTER COLUMN criado_em SET NOT NULL,
  ALTER COLUMN atualizado_em SET DEFAULT now(),
  ALTER COLUMN atualizado_em SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'perfis_user_id_fkey'
      AND conrelid = 'public.perfis'::regclass
  ) THEN
    ALTER TABLE public.perfis
      ADD CONSTRAINT perfis_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'perfis_nome_length_check'
      AND conrelid = 'public.perfis'::regclass
  ) THEN
    ALTER TABLE public.perfis
      ADD CONSTRAINT perfis_nome_length_check
      CHECK (char_length(btrim(nome)) BETWEEN 2 AND 80);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'perfis_email_lowercase_check'
      AND conrelid = 'public.perfis'::regclass
  ) THEN
    ALTER TABLE public.perfis
      ADD CONSTRAINT perfis_email_lowercase_check
      CHECK (email = lower(btrim(email)));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'perfis_vendedor_codigo_check'
      AND conrelid = 'public.perfis'::regclass
  ) THEN
    ALTER TABLE public.perfis
      ADD CONSTRAINT perfis_vendedor_codigo_check
      CHECK (papel <> 'vendedor' OR nullif(btrim(codigo_vendedor_focco), '') IS NOT NULL);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS perfis_user_id_uidx
  ON public.perfis (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS perfis_codigo_vendedor_focco_uidx
  ON public.perfis (codigo_vendedor_focco)
  WHERE codigo_vendedor_focco IS NOT NULL AND btrim(codigo_vendedor_focco) <> '';

-- Mantém id=user_id para o código já existente e também aceita o contrato novo
-- da SPEC, que cria o perfil informando user_id.
CREATE OR REPLACE FUNCTION public.sincronizar_perfil_e_timestamps()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.user_id IS NULL THEN
      NEW.user_id := NEW.id;
    ELSIF NEW.id IS NULL THEN
      NEW.id := NEW.user_id;
    END IF;

    IF NEW.id IS NULL OR NEW.user_id IS NULL OR NEW.id IS DISTINCT FROM NEW.user_id THEN
      RAISE EXCEPTION 'id e user_id devem corresponder ao mesmo usuário do Supabase Auth';
    END IF;

    NEW.criado_em := COALESCE(NEW.criado_em, NEW.created_at, now());
    NEW.created_at := NEW.criado_em;
    NEW.atualizado_em := now();
    NEW.updated_at := NEW.atualizado_em;
  ELSE
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'A identidade vinculada ao perfil não pode ser alterada';
    END IF;

    NEW.criado_em := OLD.criado_em;
    NEW.created_at := OLD.created_at;
    NEW.atualizado_em := now();
    NEW.updated_at := NEW.atualizado_em;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS perfis_sync_updated_at ON public.perfis;
DROP TRIGGER IF EXISTS perfis_sincronizar_perfil_e_timestamps ON public.perfis;
CREATE TRIGGER perfis_sincronizar_perfil_e_timestamps
  BEFORE INSERT OR UPDATE ON public.perfis
  FOR EACH ROW EXECUTE FUNCTION public.sincronizar_perfil_e_timestamps();

-- 2) O perfil é criado pelo fluxo de convite administrativo da SPEC-1-001.
-- Remove o trigger legado de signup que atribuía papel por metadata pública e
-- criava vendedores sem o código FOCCO obrigatório.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 3) Auditoria de alterações em perfis (reutilizável pelas próximas SPECs).
CREATE TABLE IF NOT EXISTS public.auditoria (
  id bigserial PRIMARY KEY,
  usuario_id uuid,
  tabela text NOT NULL,
  registro_id text NOT NULL,
  operacao text NOT NULL CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
  dados_anteriores jsonb,
  dados_novos jsonb,
  criado_em timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.registrar_auditoria()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_antes jsonb;
  v_depois jsonb;
  v_registro_id text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_depois := to_jsonb(NEW);
    v_registro_id := v_depois ->> 'id';
  ELSIF TG_OP = 'UPDATE' THEN
    v_antes := to_jsonb(OLD);
    v_depois := to_jsonb(NEW);
    v_registro_id := COALESCE(v_depois ->> 'id', v_antes ->> 'id');
  ELSE
    v_antes := to_jsonb(OLD);
    v_registro_id := v_antes ->> 'id';
  END IF;

  INSERT INTO public.auditoria (
    usuario_id, tabela, registro_id, operacao,
    dados_anteriores, dados_novos, criado_em
  ) VALUES (
    auth.uid(), TG_TABLE_NAME, COALESCE(v_registro_id, ''), TG_OP,
    v_antes, v_depois, now()
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS perfis_auditoria ON public.perfis;
CREATE TRIGGER perfis_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.perfis
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- 4) Funções de papel. SECURITY DEFINER com search_path fixo evita recursão no RLS.
CREATE OR REPLACE FUNCTION public.perfil_atual_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id
  FROM public.perfis AS p
  WHERE p.user_id = auth.uid() AND p.ativo = true
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.papel_atual()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.papel::text
  FROM public.perfis AS p
  WHERE p.user_id = auth.uid() AND p.ativo = true
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.eh_gestao()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.papel_atual() IN ('supervisora', 'diretoria', 'admin'), false);
$$;

-- Mantém o helper legado para as políticas das demais tabelas até as SPECs
-- seguintes, mas faz a consulta respeitar ativo=false e restringe o acesso anônimo.
CREATE OR REPLACE FUNCTION public.current_user_papel()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.papel_atual();
$$;

CREATE OR REPLACE FUNCTION public.registrar_acesso()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.perfis
  SET ultimo_acesso_em = now()
  WHERE user_id = auth.uid() AND ativo = true;
END;
$$;

-- 5) RLS: vendedor/PCP leem apenas o próprio perfil; gestão lê todos.
-- Zera políticas antigas porque havia uma SELECT USING (true) e políticas
-- recursivas que faziam a consulta falhar.
DO $$
DECLARE
  v_policy record;
BEGIN
  FOR v_policy IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'perfis'
  LOOP
    EXECUTE format('DROP POLICY %I ON public.perfis', v_policy.policyname);
  END LOOP;
END $$;

ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfis FORCE ROW LEVEL SECURITY;
CREATE POLICY perfis_select_por_perfil
  ON public.perfis
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT public.eh_gestao()));

-- Sem política de escrita para authenticated; somente a Edge Function (service_role)
-- administra usuários. Auditoria é consultável apenas por gestão e gravada por trigger.
ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS auditoria_select_gestao ON public.auditoria;
CREATE POLICY auditoria_select_gestao
  ON public.auditoria
  FOR SELECT TO authenticated
  USING ((SELECT public.eh_gestao()));

REVOKE ALL ON TABLE public.perfis FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.perfis TO authenticated;
GRANT ALL ON TABLE public.perfis TO service_role;

REVOKE ALL ON TABLE public.auditoria FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.auditoria TO authenticated;

REVOKE ALL ON FUNCTION public.sincronizar_perfil_e_timestamps() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.registrar_auditoria() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.perfil_atual_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.papel_atual() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.eh_gestao() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_papel() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_acesso() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.perfil_atual_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.papel_atual() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.eh_gestao() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_user_papel() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.registrar_acesso() TO authenticated, service_role;

COMMIT;
