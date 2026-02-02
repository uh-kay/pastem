-- name: GetRoleByName :one
select id, name, level, description, created_at from roles where name = $1;
