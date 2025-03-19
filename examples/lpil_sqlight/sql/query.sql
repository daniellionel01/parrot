-- name: GetCatsByAge :many
select
  name,
  age
from
  cats
where
  age < ?
