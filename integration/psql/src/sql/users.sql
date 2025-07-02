-- name: GetUser :one
SELECT
  *
FROM
  users
WHERE
  id = $1
LIMIT
  1;

-- name: ListUsers :many
SELECT
  *
FROM
  users
ORDER BY
  created_at DESC;

-- name: CreateUser :exec
INSERT INTO
  users (username)
VALUES
  (sqlc.arg(name));

-- name: UpdateUserUsername :exec
UPDATE users
SET
  username = $1
WHERE
  id = $2;

-- name: DeleteUser :exec
DELETE FROM users
WHERE
  id = $1;

-- name: GetUserByUsername :one
SELECT
  *
FROM
  users
WHERE
  username = $1
LIMIT
  1;
