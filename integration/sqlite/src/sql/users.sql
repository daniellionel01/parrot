-- name: CountUsers :many
SELECT
  count(*)
FROM
  users;

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

-- name: GetUserByUsername :one
SELECT
  *
FROM
  users
WHERE
  username = ?
LIMIT
  1;
