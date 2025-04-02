-- name: GetCatsByAge :many
select
  cast(datetime (created_at, 'localtime') as text) as timestamp,
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
