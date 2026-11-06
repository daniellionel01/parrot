-- name: Simple :one
select 1;

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
