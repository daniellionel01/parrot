-- name: InsertNameCollision :exec
insert into name_collisions (sql, ids_slice, bool_decoder, active)
values (?, ?, ?, ?);

-- `sql` and `ids_slice` are variables parrot generates, the last argument is
-- named like the row decoder, `bool_decoder` is the decoder of `active` and
-- both counts are called `count`.
-- name: NameCollisions :many
select bool_decoder, active, count(*), count(*)
from name_collisions
where sql = sqlc.arg(sql)
  and ids_slice = sqlc.arg(ids_slice)
  and bool_decoder in (sqlc.slice(ids))
  and active = sqlc.arg(name_collisions_decoder)
group by bool_decoder, active;

-- Both parameters are called `sql`.
-- name: DuplicateParameters :many
select bool_decoder from name_collisions where sql = ? or sql = ?;
