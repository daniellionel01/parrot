-- name: RowJson :one
SELECT row_to_json(t)
FROM (
  SELECT id, username, created_at
  FROM users
  WHERE id = 1
) t;


-- name: Simple :one
select 1;

-- name: CreateUserWithRole :exec
INSERT INTO
  users (username, role)
VALUES
  ($1, $2);

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

-- name: CreateUserAt :exec
INSERT INTO
  users (username, created_at)
VALUES
  ($1, to_timestamp(@created_at::float));

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

-- name: GetUserByLowerUsername :one
SELECT
  *
FROM
  users
WHERE
  username = lower($1)
LIMIT
  1;

-- name: SearchUsersByUsernamePattern :many
SELECT id, username
FROM users
WHERE username LIKE ANY(sqlc.arg(patterns)::text[]);
