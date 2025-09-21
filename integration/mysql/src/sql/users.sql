-- name: Simple :one
select 1;

-- name: GetUser :one
SELECT
  *
FROM
  users
WHERE
  id = ?
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
  (?);

-- name: UpdateUserUsername :exec
UPDATE users
SET
  username = ?
WHERE
  id = ?;

-- name: DeleteUser :exec
DELETE FROM users
WHERE
  id = ?;

-- name: GetUserByUsername :one
SELECT
  *
FROM
  users
WHERE
  username = ?
LIMIT
  1;
