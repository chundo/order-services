-- Crear bases de datos para los microservicios
CREATE DATABASE orders_development;
CREATE DATABASE orders_test;
CREATE DATABASE customers_development;
CREATE DATABASE customers_test;

-- Dar permisos al usuario monokera
GRANT ALL PRIVILEGES ON DATABASE orders_development TO monokera;
GRANT ALL PRIVILEGES ON DATABASE orders_test TO monokera;
GRANT ALL PRIVILEGES ON DATABASE customers_development TO monokera;
GRANT ALL PRIVILEGES ON DATABASE customers_test TO monokera;
