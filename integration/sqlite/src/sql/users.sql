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

-- name: CreateUserWithRole :exec
INSERT INTO
  users (username, role)
VALUES
  (?, ?);

-- name: UpdateUserUsername :exec
UPDATE users
SET
  username = ?
WHERE
  id = ?;

-- name: UpdateUserType :exec
UPDATE users
SET
  type = ?
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
