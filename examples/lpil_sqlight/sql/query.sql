-- name: GetCatsByAge :many
select
  created_at,
  name,
  age
from
  cats
where
  age < ?;

-- name: CountCats :one
select
  count(*)
from
  cats;
