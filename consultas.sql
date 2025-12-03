-- Consulta 1: Listar todos os funcionários
SELECT * FROM funcionarios;

-- Consulta 2: Listar funcionários com seus dependentes
SELECT f.nome AS funcionario,
       d.nome AS dependente,
       d.tipo_dependencia
FROM funcionarios f
LEFT JOIN dependentes d ON d.cpf_funcionario = f.cpf;

-- Consulta 3: Funcionários e suas características de saúde
SELECT f.nome,
       c.nome AS caracteristica,
       fc.ativo
FROM funcionarios f
JOIN caracteristicas_saude_funcionarios fc ON fc.cpf_funcionario = f.cpf
JOIN caracteristicas_saude c ON c.id = fc.id_caracteristica;

-- Consulta 4: Funcionários aptos e inaptos com base nos exames realizados
SELECT f.nome,
       e.descricao AS exame,
       er.valor_resultado,
       er.status_aptidao
FROM exames_realizados er
JOIN exames e ON e.id = er.id_exame
JOIN funcionarios f ON f.cpf = er.cpf_funcionario;

-- Consulta 5: Funcionários por setor
SELECT f.nome,
       s.nome AS setor,
       c.nome AS cargo
FROM historico_na_empresa h
JOIN cargos_e_setores cs ON cs.id = h.id_cargo_setor
JOIN setores s ON s.id = cs.id_setor
JOIN cargos c ON c.id = cs.id_cargo
JOIN funcionarios f ON f.cpf = h.cpf_funcionario
WHERE h.cargo_atual = TRUE;

-- Consulta 6: Treinamentos realizados pelos funcionários
SELECT f.nome,
       t.nome AS treinamento,
       tf.data_treinamento
FROM treinamento_funcionarios tf
JOIN funcionarios f ON f.cpf = tf.cpf_funcionario
JOIN treinamentos t ON t.id = tf.id_treinamento;
