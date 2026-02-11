-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS snippets (
    id bigserial primary key,
    author bigint not null references users(id),
    title varchar(255) not null,
    content text not null,
    version int not null default 1,
    expires_at bigint not null,
    updated_at bigint not null,
    created_at bigint not null
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS snippets;
-- +goose StatementEnd
