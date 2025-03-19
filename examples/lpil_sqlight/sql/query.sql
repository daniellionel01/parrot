-- name: GetCatsByAge :many
select
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
