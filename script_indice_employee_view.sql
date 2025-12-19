-- =====================================================================
-- COMPANY - Views de personalização de acesso + permissões
-- MySQL 8.0
-- =====================================================================

USE company;

-- 1) Número de empregados por departamento e localidade
-- Obs.: employees estão vinculados ao departamento; se o depto tiver
-- múltiplas localidades, a contagem se repete por localidade.
CREATE OR REPLACE VIEW v_emp_por_depto_localidade AS
SELECT
  d.dnumber       AS dept_no,
  d.dname         AS departamento,
  dl.dlocation    AS localidade,
  COUNT(e.ssn)    AS total_empregados
FROM department d
JOIN dept_locations dl
  ON dl.dnumber = d.dnumber
LEFT JOIN employee e
  ON e.dno = d.dnumber
GROUP BY d.dnumber, d.dname, dl.dlocation;

-- 2) Lista de departamentos e seus gerentes
CREATE OR REPLACE VIEW v_departamentos_gerentes AS
SELECT
  d.dnumber                  AS dept_no,
  d.dname                    AS departamento,
  CONCAT(m.fname, ' ', m.lname) AS gerente,
  d.mgr_ssn,
  d.mgr_start_date
FROM department d
LEFT JOIN employee m
  ON m.ssn = d.mgr_ssn;

-- 3) Projetos com número de empregados
-- Use ORDER BY na consulta sobre a view para ver “maior número” primeiro
CREATE OR REPLACE VIEW v_projetos_qtd_empregados AS
SELECT
  p.pnumber       AS projeto_no,
  p.pname         AS projeto,
  p.dnum          AS dept_no,
  COUNT(DISTINCT w.essn) AS qtd_empregados
FROM project p
LEFT JOIN works_on w
  ON w.pno = p.pnumber
GROUP BY p.pnumber, p.pname, p.dnum;

-- 4) Lista de projetos, seus departamentos e gerentes
CREATE OR REPLACE VIEW v_projetos_departamentos_gerentes AS
SELECT
  p.pnumber                     AS projeto_no,
  p.pname                       AS projeto,
  d.dnumber                     AS dept_no,
  d.dname                       AS departamento,
  CONCAT(m.fname, ' ', m.lname) AS gerente,
  d.mgr_ssn
FROM project p
JOIN department d
  ON d.dnumber = p.dnum
LEFT JOIN employee m
  ON m.ssn = d.mgr_ssn;

-- 5) Empregados que possuem dependentes e se são gerentes
CREATE OR REPLACE VIEW v_emp_dependentes_e_gerencia AS
SELECT
  e.ssn,
  CONCAT(e.fname, ' ', e.lname) AS empregado,
  COUNT(dpt.dependent_name)     AS qtd_dependentes,
  CASE
    WHEN EXISTS (SELECT 1 FROM department d WHERE d.mgr_ssn = e.ssn) THEN 1
    ELSE 0
  END AS is_gerente
FROM employee e
LEFT JOIN `dependent` dpt
  ON dpt.essn = e.ssn
GROUP BY e.ssn, e.fname, e.lname;

-- (Opcional) Versões “públicas” sem info de departamento/gerente,
-- para perfis com acesso restrito
CREATE OR REPLACE VIEW v_projetos_publico AS
SELECT projeto_no, projeto, qtd_empregados
FROM v_projetos_qtd_empregados;

CREATE OR REPLACE VIEW v_emp_dependentes_publico AS
SELECT ssn, empregado, qtd_dependentes
FROM v_emp_dependentes_e_gerencia;

-- =====================================================================
-- Permissões por perfil de usuário
-- - usuário gerente: acesso às informações de employee e department,
--   e a TODAS as views acima
-- - usuário employee: NÃO tem acesso a dept/gerentes; recebe apenas
--   views “públicas” sem info de dept/gerente
-- =====================================================================

-- Criação de usuários (ajuste host e senhas conforme sua política)
CREATE USER IF NOT EXISTS 'gerente_app'@'%' IDENTIFIED BY 'SenhaForteGerente#2025';
CREATE USER IF NOT EXISTS 'employee_app'@'%' IDENTIFIED BY 'SenhaForteEmployee#2025';

-- Permissões para gerente: pode consultar employee/department + todas as views
GRANT SELECT ON company.employee  TO 'gerente_app'@'%';
GRANT SELECT ON company.department TO 'gerente_app'@'%';

GRANT SELECT ON company.v_emp_por_depto_localidade        TO 'gerente_app'@'%';
GRANT SELECT ON company.v_departamentos_gerentes          TO 'gerente_app'@'%';
GRANT SELECT ON company.v_projetos_qtd_empregados         TO 'gerente_app'@'%';
GRANT SELECT ON company.v_projetos_departamentos_gerentes TO 'gerente_app'@'%';
GRANT SELECT ON company.v_emp_dependentes_e_gerencia      TO 'gerente_app'@'%';

-- Permissões para employee (restrito): apenas views sem dept/gerentes
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'employee_app'@'%';
GRANT SELECT ON company.v_projetos_publico            TO 'employee_app'@'%';
GRANT SELECT ON company.v_emp_dependentes_publico     TO 'employee_app'@'%';

-- Confirma privilégios
FLUSH PRIVILEGES;

-- =====================================================================
-- Exemplos de uso
-- =====================================================================

-- Projetos com maior número de empregados (ordenar ao consultar a view)
-- (como gerente ou employee, dependendo da view escolhida)
-- SELECT * FROM v_projetos_qtd_empregados ORDER BY qtd_empregados DESC;
-- SELECT * FROM v_projetos_publico        ORDER BY qtd_empregados DESC;

-- Demais views (acesso do gerente)
-- SELECT * FROM v_emp_por_depto_localidade;
-- SELECT * FROM v_departamentos_gerentes;
-- SELECT * FROM v_projetos_departamentos_gerentes;
-- SELECT * FROM v_emp_dependentes_e_gerencia;
