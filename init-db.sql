-- Script de inicialización de BD para Fichaje
-- Se ejecuta automáticamente en el primer start de MySQL

-- Crear base de datos
CREATE DATABASE IF NOT EXISTS db_fichajespi_prod 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE db_fichajespi_prod;

-- Crear usuario específico
CREATE USER IF NOT EXISTS 'fichajes_prod'@'%' IDENTIFIED BY 'fichajes_prod';
GRANT ALL PRIVILEGES ON db_fichajespi_prod.* TO 'fichajes_prod'@'%';
FLUSH PRIVILEGES;

-- Crear usuario local
CREATE USER IF NOT EXISTS 'fichajes_prod'@'localhost' IDENTIFIED BY 'fichajes_prod';
GRANT ALL PRIVILEGES ON db_fichajespi_prod.* TO 'fichajes_prod'@'localhost';
FLUSH PRIVILEGES;

-- Crear usuario root local (si no existe)
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED WITH mysql_native_password AS '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Mostrar usuarios creados
SELECT user, host FROM mysql.user WHERE user IN ('fichajes_prod', 'root');

-- Verificar permisos
SHOW GRANTS FOR 'fichajes_prod'@'%';

-- Mostrar estado
SELECT 'Inicialización completada' as status;
