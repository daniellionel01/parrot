-- name: AuthorPosts :many
SELECT
  *
FROM
  posts
  INNER JOIN authors on authors.id = posts.author_id
WHERE
  authors.id = ?;
