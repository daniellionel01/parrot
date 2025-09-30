-- name: RowJson :one
SELECT row_to_json(t)
FROM (
  SELECT id, username, created_at
  FROM users
  WHERE id = 1
) t;


-- name: Simple :one
select 1;

-- name: CreatedAtAsText :one
SELECT created_at::text FROM users WHERE id = $1;

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

-- name: CreateUserWithDateOfBirth :exec
INSERT INTO users (username, created_at, date_of_birth)
VALUES (@username, CURRENT_TIMESTAMP, TO_TIMESTAMP(@date_of_birth::text, 'YYYY-MM-DDZ'));

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

-- name: PostsByUsername :many
select
  id,
  title,
  user_id
from posts
where user_id = (
  select id
  from users
  where username = $1
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
