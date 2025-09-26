CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS hstore;

DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS user_role;

CREATE TYPE user_role AS ENUM ('admin', 'user', 'guest');

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  date_of_birth DATE,

  profile JSONB,
  extra_info JSON,

  favorite_numbers INTEGER[],
  role user_role,
  document BYTEA
);
