-- Criação do banco de dados
CREATE DATABASE SistemaGestao;
USE SistemaGestao;

-- Tabela de Usuários (para login)
CREATE TABLE Usuarios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    nivel_acesso ENUM('admin', 'usuario') DEFAULT 'usuario',
    data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    ultimo_acesso DATETIME NULL
);

-- Tabela de Voluntários
CREATE TABLE Voluntarios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    rg VARCHAR(20) NOT NULL,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    telefone VARCHAR(20) NOT NULL,
    endereco VARCHAR(255) NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    ativo BOOLEAN DEFAULT TRUE
);

-- Tabela de Tipos de Doações
CREATE TABLE TiposDoacoes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL UNIQUE,
    descricao TEXT NULL
);

-- Inserir tipos básicos de doações
INSERT INTO TiposDoacoes (nome) VALUES ('Roupa'), ('Comida'), ('Brinquedo');

-- Tabela de Doações
CREATE TABLE Doacoes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tipo_id INT NOT NULL,
    descricao TEXT NOT NULL,
    quantidade INT NOT NULL,
    data_doacao DATE NOT NULL,
    doador VARCHAR(100) NULL,
    recebido_por INT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tipo_id) REFERENCES TiposDoacoes(id),
    FOREIGN KEY (recebido_por) REFERENCES Voluntarios(id)
);

-- Tabela de Responsáveis
CREATE TABLE Responsaveis (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    endereco VARCHAR(255) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(100) NULL,
    cpf VARCHAR(14) NULL UNIQUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de Alunos
CREATE TABLE Alunos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    genero ENUM('Masculino', 'Feminino', 'Outro') NOT NULL,
    data_nascimento DATE NOT NULL,
    escola VARCHAR(100) NOT NULL,
    serie VARCHAR(50) NOT NULL,
    responsavel_id INT NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    ativo BOOLEAN DEFAULT TRUE,
    codigo_qr VARCHAR(255) NULL UNIQUE,
    FOREIGN KEY (responsavel_id) REFERENCES Responsaveis(id)
);

-- Tabela de Chamadas
CREATE TABLE Chamadas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    data DATE NOT NULL,
    descricao VARCHAR(255) NULL,
    criado_por INT NOT NULL,
    data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (criado_por) REFERENCES Usuarios(id)
);

-- Tabela de Presenças
CREATE TABLE Presencas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    chamada_id INT NOT NULL,
    aluno_id INT NOT NULL,
    presente BOOLEAN DEFAULT TRUE,
    hora_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    registrado_por INT NOT NULL,
    FOREIGN KEY (chamada_id) REFERENCES Chamadas(id),
    FOREIGN KEY (aluno_id) REFERENCES Alunos(id),
    FOREIGN KEY (registrado_por) REFERENCES Usuarios(id),
    UNIQUE (chamada_id, aluno_id)
);

-- Views para relatórios

-- View para relatório de doações por período
CREATE VIEW vw_relatorio_doacoes AS
SELECT 
    d.id, 
    t.nome AS tipo_doacao, 
    d.descricao, 
    d.quantidade, 
    d.data_doacao, 
    d.doador, 
    v.nome AS recebido_por
FROM Doacoes d
JOIN TiposDoacoes t ON d.tipo_id = t.id
LEFT JOIN Voluntarios v ON d.recebido_por = v.id;

-- View para relatório de alunos por gênero e idade
CREATE VIEW vw_relatorio_alunos AS
SELECT 
    a.id,
    a.nome,
    a.genero,
    a.data_nascimento,
    TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade,
    a.escola,
    a.serie,
    r.nome AS responsavel,
    r.telefone AS telefone_responsavel
FROM Alunos a
JOIN Responsaveis r ON a.responsavel_id = r.id
WHERE a.ativo = TRUE;

-- View para relatório de presenças semanais
CREATE VIEW vw_relatorio_presencas_semanais AS
SELECT 
    c.data,
    a.id AS aluno_id,
    a.nome AS aluno_nome,
    a.genero,
    TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade,
    IF(p.presente, 'Presente', 'Ausente') AS status_presenca
FROM Chamadas c
CROSS JOIN Alunos a
LEFT JOIN Presencas p ON c.id = p.chamada_id AND a.id = p.aluno_id
WHERE a.ativo = TRUE
ORDER BY c.data DESC, a.nome;

-- Stored Procedures para relatórios

-- Procedure para relatório de doações por período
DELIMITER //
CREATE PROCEDURE sp_relatorio_doacoes_periodo(
    IN data_inicio DATE,
    IN data_fim DATE,
    IN tipo_id INT
)
BEGIN
    IF tipo_id IS NULL THEN
        SELECT * FROM vw_relatorio_doacoes
        WHERE data_doacao BETWEEN data_inicio AND data_fim
        ORDER BY data_doacao;
    ELSE
        SELECT * FROM vw_relatorio_doacoes
        WHERE data_doacao BETWEEN data_inicio AND data_fim
        AND tipo_doacao = (SELECT nome FROM TiposDoacoes WHERE id = tipo_id)
        ORDER BY data_doacao;
    END IF;
END //
DELIMITER ;

-- Procedure para relatório de alunos por gênero e faixa etária
DELIMITER //
CREATE PROCEDURE sp_relatorio_alunos_genero_idade(
    IN genero_param VARCHAR(20),
    IN idade_min INT,
    IN idade_max INT
)
BEGIN
    IF genero_param IS NULL THEN
        SELECT * FROM vw_relatorio_alunos
        WHERE idade BETWEEN idade_min AND idade_max
        ORDER BY nome;
    ELSE
        SELECT * FROM vw_relatorio_alunos
        WHERE genero = genero_param
        AND idade BETWEEN idade_min AND idade_max
        ORDER BY nome;
    END IF;
END //
DELIMITER ;

-- Procedure para gerar código QR único para aluno
DELIMITER //
CREATE PROCEDURE sp_gerar_codigo_qr_aluno(
    IN aluno_id INT
)
BEGIN
    DECLARE codigo VARCHAR(255);
    SET codigo = CONCAT('ALN', aluno_id, '-', SUBSTRING(MD5(RAND()), 1, 10));
    
    UPDATE Alunos SET codigo_qr = codigo WHERE id = aluno_id;
    
    SELECT codigo AS codigo_qr;
END //
DELIMITER ;

-- Triggers

-- Trigger para gerar código QR ao cadastrar aluno
DELIMITER //
CREATE TRIGGER trg_gerar_qr_aluno
AFTER INSERT ON Alunos
FOR EACH ROW
BEGIN
    CALL sp_gerar_codigo_qr_aluno(NEW.id);
END //
DELIMITER ;

-- Índices para otimização de consultas
CREATE INDEX idx_alunos_genero ON Alunos(genero);
CREATE INDEX idx_alunos_nascimento ON Alunos(data_nascimento);
CREATE INDEX idx_doacoes_data ON Doacoes(data_doacao);
CREATE INDEX idx_presencas_chamada ON Presencas(chamada_id);
CREATE INDEX idx_chamadas_data ON Chamadas(data);-- Criação do banco de dados
CREATE DATABASE SistemaGestao;
USE SistemaGestao;

-- Tabela de Usuários (para login)
CREATE TABLE Usuarios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    nivel_acesso ENUM('admin', 'usuario') DEFAULT 'usuario',
    data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    ultimo_acesso DATETIME NULL
);

-- Tabela de Voluntários
CREATE TABLE Voluntarios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    rg VARCHAR(20) NOT NULL,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    telefone VARCHAR(20) NOT NULL,
    endereco VARCHAR(255) NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    ativo BOOLEAN DEFAULT TRUE
);

-- Tabela de Tipos de Doações
CREATE TABLE TiposDoacoes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL UNIQUE,
    descricao TEXT NULL
);

-- Inserir tipos básicos de doações
INSERT INTO TiposDoacoes (nome) VALUES ('Roupa'), ('Comida'), ('Brinquedo');

-- Tabela de Doações
CREATE TABLE Doacoes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tipo_id INT NOT NULL,
    descricao TEXT NOT NULL,
    quantidade INT NOT NULL,
    data_doacao DATE NOT NULL,
    doador VARCHAR(100) NULL,
    recebido_por INT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tipo_id) REFERENCES TiposDoacoes(id),
    FOREIGN KEY (recebido_por) REFERENCES Voluntarios(id)
);

-- Tabela de Responsáveis
CREATE TABLE Responsaveis (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    endereco VARCHAR(255) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(100) NULL,
    cpf VARCHAR(14) NULL UNIQUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de Alunos
CREATE TABLE Alunos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    genero ENUM('Masculino', 'Feminino', 'Outro') NOT NULL,
    data_nascimento DATE NOT NULL,
    escola VARCHAR(100) NOT NULL,
    serie VARCHAR(50) NOT NULL,
    responsavel_id INT NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    ativo BOOLEAN DEFAULT TRUE,
    codigo_qr VARCHAR(255) NULL UNIQUE,
    FOREIGN KEY (responsavel_id) REFERENCES Responsaveis(id)
);

-- Tabela de Chamadas
CREATE TABLE Chamadas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    data DATE NOT NULL,
    descricao VARCHAR(255) NULL,
    criado_por INT NOT NULL,
    data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (criado_por) REFERENCES Usuarios(id)
);

-- Tabela de Presenças
CREATE TABLE Presencas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    chamada_id INT NOT NULL,
    aluno_id INT NOT NULL,
    presente BOOLEAN DEFAULT TRUE,
    hora_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    registrado_por INT NOT NULL,
    FOREIGN KEY (chamada_id) REFERENCES Chamadas(id),
    FOREIGN KEY (aluno_id) REFERENCES Alunos(id),
    FOREIGN KEY (registrado_por) REFERENCES Usuarios(id),
    UNIQUE (chamada_id, aluno_id)
);

-- Views para relatórios

-- View para relatório de doações por período
CREATE VIEW vw_relatorio_doacoes AS
SELECT 
    d.id, 
    t.nome AS tipo_doacao, 
    d.descricao, 
    d.quantidade, 
    d.data_doacao, 
    d.doador, 
    v.nome AS recebido_por
FROM Doacoes d
JOIN TiposDoacoes t ON d.tipo_id = t.id
LEFT JOIN Voluntarios v ON d.recebido_por = v.id;

-- View para relatório de alunos por gênero e idade
CREATE VIEW vw_relatorio_alunos AS
SELECT 
    a.id,
    a.nome,
    a.genero,
    a.data_nascimento,
    TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade,
    a.escola,
    a.serie,
    r.nome AS responsavel,
    r.telefone AS telefone_responsavel
FROM Alunos a
JOIN Responsaveis r ON a.responsavel_id = r.id
WHERE a.ativo = TRUE;

-- View para relatório de presenças semanais
CREATE VIEW vw_relatorio_presencas_semanais AS
SELECT 
    c.data,
    a.id AS aluno_id,
    a.nome AS aluno_nome,
    a.genero,
    TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade,
    IF(p.presente, 'Presente', 'Ausente') AS status_presenca
FROM Chamadas c
CROSS JOIN Alunos a
LEFT JOIN Presencas p ON c.id = p.chamada_id AND a.id = p.aluno_id
WHERE a.ativo = TRUE
ORDER BY c.data DESC, a.nome;

-- Stored Procedures para relatórios

-- Procedure para relatório de doações por período
DELIMITER //
CREATE PROCEDURE sp_relatorio_doacoes_periodo(
    IN data_inicio DATE,
    IN data_fim DATE,
    IN tipo_id INT
)
BEGIN
    IF tipo_id IS NULL THEN
        SELECT * FROM vw_relatorio_doacoes
        WHERE data_doacao BETWEEN data_inicio AND data_fim
        ORDER BY data_doacao;
    ELSE
        SELECT * FROM vw_relatorio_doacoes
        WHERE data_doacao BETWEEN data_inicio AND data_fim
        AND tipo_doacao = (SELECT nome FROM TiposDoacoes WHERE id = tipo_id)
        ORDER BY data_doacao;
    END IF;
END //
DELIMITER ;

-- Procedure para relatório de alunos por gênero e faixa etária
DELIMITER //
CREATE PROCEDURE sp_relatorio_alunos_genero_idade(
    IN genero_param VARCHAR(20),
    IN idade_min INT,
    IN idade_max INT
)
BEGIN
    IF genero_param IS NULL THEN
        SELECT * FROM vw_relatorio_alunos
        WHERE idade BETWEEN idade_min AND idade_max
        ORDER BY nome;
    ELSE
        SELECT * FROM vw_relatorio_alunos
        WHERE genero = genero_param
        AND idade BETWEEN idade_min AND idade_max
        ORDER BY nome;
    END IF;
END //
DELIMITER ;

-- Procedure para gerar código QR único para aluno
DELIMITER //
CREATE PROCEDURE sp_gerar_codigo_qr_aluno(
    IN aluno_id INT
)
BEGIN
    DECLARE codigo VARCHAR(255);
    SET codigo = CONCAT('ALN', aluno_id, '-', SUBSTRING(MD5(RAND()), 1, 10));
    
    UPDATE Alunos SET codigo_qr = codigo WHERE id = aluno_id;
    
    SELECT codigo AS codigo_qr;
END //
DELIMITER ;

-- Triggers

-- Trigger para gerar código QR ao cadastrar aluno
DELIMITER //
CREATE TRIGGER trg_gerar_qr_aluno
AFTER INSERT ON Alunos
FOR EACH ROW
BEGIN
    CALL sp_gerar_codigo_qr_aluno(NEW.id);
END //
DELIMITER ;

-- Índices para otimização de consultas
CREATE INDEX idx_alunos_genero ON Alunos(genero);
CREATE INDEX idx_alunos_nascimento ON Alunos(data_nascimento);
CREATE INDEX idx_doacoes_data ON Doacoes(data_doacao);
CREATE INDEX idx_presencas_chamada ON Presencas(chamada_id);
CREATE INDEX idx_chamadas_data ON Chamadas(data);