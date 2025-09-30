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


-- name: PostsByUsername :many
select
  id,
  title,
  user_id
from posts
where user_id = (
  select id
  from users
  where username = ?
);

-- name: PostsByAdmins :many
select
  id,
  title,
  user_id
from posts
where user_id in (
  select id
  from users
  where users.role = 'admin'
);
