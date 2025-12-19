-- =====================================================================
-- E-COMMERCE - Triggers: BEFORE DELETE (cliente) e BEFORE UPDATE (colaborador)
-- MySQL 8.0
-- =====================================================================

CREATE DATABASE IF NOT EXISTS ecommerce_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE ecommerce_db;

-- =========================
-- Tabelas base (mínimas)
-- =========================

-- Usuários/clientes da loja
CREATE TABLE IF NOT EXISTS cliente (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  cpf_cnpj VARCHAR(20) NOT NULL UNIQUE,
  data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  -- Campo opcional para o app informar o motivo antes de deletar (trigger lê de OLD)
  motivo_exclusao VARCHAR(255) NULL
) ENGINE=InnoDB;

-- Tabela de auditoria de exclusões de clientes
CREATE TABLE IF NOT EXISTS cliente_exclusao_log (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  cliente_id BIGINT NOT NULL,
  nome VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL,
  cpf_cnpj VARCHAR(20) NOT NULL,
  data_cadastro DATETIME NOT NULL,
  data_exclusao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  motivo_exclusao VARCHAR(255) NULL,
  origem VARCHAR(50) NOT NULL DEFAULT 'TRIGGER',
  INDEX (cliente_id)
) ENGINE=InnoDB;

-- Colaboradores (funcionários da operação)
CREATE TABLE IF NOT EXISTS colaborador (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  cargo VARCHAR(100) NOT NULL,
  salario_base DECIMAL(12,2) NOT NULL,
  data_admissao DATE NULL,
  data_rescisao DATE NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  ativo TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

-- Histórico de alterações salariais
CREATE TABLE IF NOT EXISTS historico_salario (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  colaborador_id BIGINT NOT NULL,
  salario_antigo DECIMAL(12,2) NULL,
  salario_novo DECIMAL(12,2) NOT NULL,
  alterado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  motivo VARCHAR(255) NULL,
  usuario_responsavel VARCHAR(100) NULL,
  CONSTRAINT fk_hist_colab FOREIGN KEY (colaborador_id) REFERENCES colaborador(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX (colaborador_id, alterado_em)
) ENGINE=InnoDB;

-- =========================
-- TRIGGERS
-- =========================
DELIMITER $$

-- BEFORE DELETE: arquiva dados do cliente antes de remover
DROP TRIGGER IF EXISTS trg_cliente_before_delete $$
CREATE TRIGGER trg_cliente_before_delete
BEFORE DELETE ON cliente
FOR EACH ROW
BEGIN
  INSERT INTO cliente_exclusao_log
    (cliente_id, nome, email, cpf_cnpj, data_cadastro, motivo_exclusao)
  VALUES
    (OLD.id, OLD.nome, OLD.email, OLD.cpf_cnpj, OLD.data_cadastro,
     COALESCE(OLD.motivo_exclusao, 'exclusao voluntaria'));
END $$

-- BEFORE UPDATE: valida e registra mudança de salário
DROP TRIGGER IF EXISTS trg_colaborador_before_update $$
CREATE TRIGGER trg_colaborador_before_update
BEFORE UPDATE ON colaborador
FOR EACH ROW
BEGIN
  -- Validação de salário
  IF NEW.salario_base IS NULL OR NEW.salario_base < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Salario base inválido (NULL/negativo)';
  END IF;

  -- Se houve alteração de salário, registra no histórico
  IF NEW.salario_base <> OLD.salario_base THEN
    INSERT INTO historico_salario
      (colaborador_id, salario_antigo, salario_novo, motivo, usuario_responsavel)
    VALUES
      (OLD.id, OLD.salario_base, NEW.salario_base, 'Ajuste salarial', CURRENT_USER());
  END IF;

  -- updated_at já é atualizado automaticamente pelo ON UPDATE
END $$

-- (Opcional) BEFORE INSERT: garante admissão e valida salário no momento da criação
DROP TRIGGER IF EXISTS trg_colaborador_before_insert $$
CREATE TRIGGER trg_colaborador_before_insert
BEFORE INSERT ON colaborador
FOR EACH ROW
BEGIN
  IF NEW.salario_base IS NULL OR NEW.salario_base < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Salario base inválido (NULL/negativo) na admissão';
  END IF;

  IF NEW.data_admissao IS NULL THEN
    SET NEW.data_admissao = CURDATE();
  END IF;
END $$

DELIMITER ;

-- =========================
-- DADOS DE TESTE RÁPIDO
-- =========================

-- Clientes
INSERT INTO cliente (nome, email, cpf_cnpj) VALUES
('Ana Cliente', 'ana@cliente.com', '111.111.111-11'),
('Bruno Cliente', 'bruno@cliente.com', '222.222.222-22');

-- Colaboradores
INSERT INTO colaborador (nome, cargo, salario_base, data_admissao) VALUES
('Carla Gerente', 'Gerente de Operações', 6500.00, CURDATE()),
('Diego Suporte', 'Analista de Suporte', 3200.00, CURDATE());

-- Atualização de salário (gera registro no histórico)
UPDATE colaborador
   SET salario_base = 7000.00
 WHERE nome = 'Carla Gerente';

-- Exclusão de cliente com motivo (arquiva no log e depois remove)
UPDATE cliente SET motivo_exclusao = 'pedido do usuário via app' WHERE email = 'bruno@cliente.com';
DELETE FROM cliente WHERE email = 'bruno@cliente.com';

-- Consultas de verificação
-- SELECT * FROM historico_salario ORDER BY alterado_em DESC;
-- SELECT * FROM cliente_exclusao_log ORDER BY data_exclusao DESC;
