DROP TABLE IF EXISTS "users";

CREATE TABLE "users" (
  id SERIAL PRIMARY KEY,
  col_int INT,
  col_varchar_nullable VARCHAR(255),
  col_varchar_notnull VARCHAR(255) NOT NULL,
  col_text TEXT
);

INSERT INTO
  "users"
VALUES
  (1, 123, 'danny', 'danny not null');
