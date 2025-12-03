-- Listagem dos funcionarios: nome, cpf, setor atual, cargo atual, data de início no cargo atual e último laudo (APTO/INAPTO)

SELECT
    f.nome,
    f.cpf,
    s.nome AS setor_atual,
    c.nome AS cargo_atual,
    h.data_inicio,
    er.status_aptidao AS ultimo_laudo
FROM funcionarios f
LEFT JOIN historico_na_empresa h
    ON h.cpf_funcionario = f.cpf AND h.cargo_atual = TRUE
LEFT JOIN cargos_e_setores cs
    ON cs.id_cargo_setor = h.id_cargo_setor
LEFT JOIN setores s
    ON s.id_setor = cs.id_setor
LEFT JOIN cargos c
    ON c.id_cargo = cs.id_cargo
LEFT JOIN (
    -- último exame por funcionário (pela data)
    SELECT xr.cpf_funcionario, xr.status_aptidao
    FROM exames_realizados xr
    JOIN (
        SELECT cpf_funcionario, MAX(data_exame) AS max_dt
        FROM exames_realizados
        GROUP BY cpf_funcionario
    ) lastxr
    ON lastxr.cpf_funcionario = xr.cpf_funcionario AND lastxr.max_dt = xr.data_exame
) er
    ON er.cpf_funcionario = f.cpf
ORDER BY s.nome, f.nome;



-- Funcionários Aptos com Dependentes e Última Glicemia
SELECT
    f.nome,
    f.estado_civil,
    CASE WHEN csf.id_caracteristica IS NULL THEN 'Não' ELSE 'Sim' END AS doador_orgaos,
    GROUP_CONCAT(d.nome SEPARATOR '; ') AS dependentes,
    xr.valor_resultado AS ultima_glicemia
FROM funcionarios f

-- característica “doador de órgãos” (id_caracteristica = 8)
LEFT JOIN caracteristicas_saude_funcionarios csf
       ON csf.cpf_funcionario = f.cpf
      AND csf.id_caracteristica = 8
      AND csf.ativo = TRUE

-- dependentes
LEFT JOIN dependentes d
       ON d.cpf_funcionario = f.cpf

-- último exame de glicemia
LEFT JOIN (
    SELECT er.cpf_funcionario, er.valor_resultado
    FROM exames_realizados er
    JOIN exames ex
      ON ex.id_exame = er.id_exame
     AND ex.descricao = 'Glicemia'
    JOIN (
        SELECT er2.cpf_funcionario, MAX(er2.data_exame) AS ultima_data
        FROM exames_realizados er2
        JOIN exames ex2
          ON ex2.id_exame = er2.id_exame
         AND ex2.descricao = 'Glicemia'
        GROUP BY er2.cpf_funcionario
    ) ult
      ON ult.cpf_funcionario = er.cpf_funcionario
     AND ult.ultima_data = er.data_exame
) xr
ON xr.cpf_funcionario = f.cpf

-- apenas funcionários APTO no último exame
WHERE f.cpf IN (
    SELECT er3.cpf_funcionario
    FROM exames_realizados er3
    JOIN (
        SELECT cpf_funcionario, MAX(data_exame) AS max_dt
        FROM exames_realizados
        GROUP BY cpf_funcionario
    ) ult2
      ON ult2.cpf_funcionario = er3.cpf_funcionario
     AND ult2.max_dt = er3.data_exame
    WHERE er3.status_aptidao = 'APTO'
)

GROUP BY
    f.cpf,
    f.nome,
    f.estado_civil,
    doador_orgaos,
    xr.valor_resultado;


-- Análise de Gap de Competências por Função

SELECT
    f.nome,
    f.escolaridade,
    c.nome AS cargo_atual,
    COUNT(DISTINCT cr.id_competencia) AS competencias_exigidas,
    COUNT(DISTINCT cf.id_competencia) AS competencias_possuidas,
    CASE
        WHEN COUNT(DISTINCT cf.id_competencia) = COUNT(DISTINCT cr.id_competencia)
        THEN 'SIM'
        ELSE 'NÃO'
    END AS atende_total,
    (COUNT(DISTINCT cr.id_competencia) - COUNT(DISTINCT cf.id_competencia)) AS competencias_faltantes
FROM funcionarios f
JOIN historico_na_empresa h
      ON h.cpf_funcionario = f.cpf AND h.cargo_atual = TRUE
JOIN cargos_e_setores cs
      ON cs.id_cargo_setor = h.id_cargo_setor
JOIN cargos c
      ON c.id_cargo = cs.id_cargo
JOIN cargos_requisitos cr
      ON cr.id_cargo_setor = cs.id_cargo_setor
LEFT JOIN competencias_funcionarios cf
      ON cf.cpf_funcionario = f.cpf
      AND cf.id_competencia = cr.id_competencia
GROUP BY
    f.cpf,
    f.nome,
    f.escolaridade,
    c.nome,
    cs.id_cargo_setor;


-- Análise de Férias por Setor (> 30%):


WITH periodo AS (
    SELECT 
        DATE('2024-01-01') AS dt_ini,
        DATE('2024-02-28') AS dt_fim
),

-- Total de funcionários por setor (considerando cargo atual)
totais AS (
    SELECT 
        s.nome AS setor,
        COUNT(*) AS total_funcionarios
    FROM funcionarios f
    JOIN historico_na_empresa h 
         ON h.cpf_funcionario = f.cpf AND h.cargo_atual = TRUE
    JOIN cargos_e_setores cs 
         ON cs.id_cargo_setor = h.id_cargo_setor
    JOIN setores s 
         ON s.id_setor = cs.id_setor
    GROUP BY s.nome
),

-- Funcionários que tiveram qualquer interseção com férias no período
ferias_setor AS (
    SELECT 
        s.nome AS setor,
        COUNT(DISTINCT f.cpf_funcionario) AS funcionarios_em_ferias
    FROM ferias f
    CROSS JOIN periodo p
    JOIN historico_na_empresa h 
         ON h.cpf_funcionario = f.cpf_funcionario AND h.cargo_atual = TRUE
    JOIN cargos_e_setores cs 
         ON cs.id_cargo_setor = h.id_cargo_setor
    JOIN setores s 
         ON s.id_setor = cs.id_setor
    WHERE 
        f.data_inicio <= p.dt_fim
        AND f.data_fim >= p.dt_ini
    GROUP BY s.nome
)

SELECT 
    t.setor,
    t.total_funcionarios,
    COALESCE(f.funcionarios_em_ferias, 0) AS funcionarios_em_ferias,
    ROUND(
        (COALESCE(f.funcionarios_em_ferias, 0) / t.total_funcionarios) * 100,
        2
    ) AS percentual_em_ferias
FROM totais t
LEFT JOIN ferias_setor f 
       ON f.setor = t.setor
WHERE 
    (COALESCE(f.funcionarios_em_ferias, 0) / t.total_funcionarios) > 0.30
ORDER BY percentual_em_ferias DESC;


-- Top 5 Funcionários por Horas de Treinamento (Avançado):



WITH period AS (
SELECT DATE_SUB(CURDATE(), INTERVAL 2 YEAR) AS dt_ini
),


-- Soma das horas de treinamento por funcionário no período
horas AS (
SELECT
tf.cpf_funcionario,
SUM(t.carga_horaria) AS total_horas
FROM treinamento_funcionarios tf
JOIN treinamentos t ON t.id_treinamento = tf.id_treinamento
CROSS JOIN period p
WHERE tf.data_treinamento >= p.dt_ini
GROUP BY tf.cpf_funcionario
),


-- Competências adquiridas via treinamentos
competencias_acq AS (
S
