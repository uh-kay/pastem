-- +goose Up
-- +goose StatementBegin
CREATE TABLE if not exists users (
    id bigserial primary key,
    username varchar(255) unique not null,
    email citext unique not null,
    password_hash bytea not null,
    created_at timestamp not null default now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
drop table if exists users;
-- +goose StatementEnd
