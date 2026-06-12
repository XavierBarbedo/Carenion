-- 1. Adicionar coluna foto_url à tabela users se não existir
ALTER TABLE users
ADD COLUMN IF NOT EXISTS foto_url TEXT;

-- 2. Atualizar ou criar a função register_cuidadora para aceitar p_foto_url
CREATE OR REPLACE FUNCTION register_cuidadora(
  p_user_id uuid,
  p_nome text,
  p_email text,
  p_familia_id int8,
  p_foto_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Inserir perfil na tabela users
  INSERT INTO users (
    id,
    nome,
    email,
    tipo,
    foto_url,
    created_at
  )
  VALUES (
    p_user_id,
    p_nome,
    p_email,
    'cuidadora',
    p_foto_url,
    now()
  );

  -- Associar à família
  INSERT INTO familia_cuidadores (
    familia_id,
    cuidadora_id,
    criado_em
  )
  VALUES (
    p_familia_id,
    p_user_id,
    now()
  );
END;
$$;
