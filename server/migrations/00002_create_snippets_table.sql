-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS snippets (
    id bigserial primary key,
    author bigint not null references users(id),
    title varchar(255) not null,
    content text not null,
    expires_at timestamp not null,
    created_at timestamp not null default now()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS snippets;
-- +goose StatementEnd
