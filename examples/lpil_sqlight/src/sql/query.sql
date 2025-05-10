-- name: GetAuthor :one
SELECT
  *
FROM
  authors
WHERE
  id = ?
LIMIT
  1;
