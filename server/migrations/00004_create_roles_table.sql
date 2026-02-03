-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS roles (
    id BIGSERIAL primary key,
    name varchar(255) not null unique,
    level int not null default 0,
    description text,
    created_at bigint not null
);

INSERT INTO roles (name, description, level, created_at)
VALUES ('user', 'can create snippets', 1, 1770141720);

INSERT INTO roles (name, description, level, created_at)
VALUES ('admin', 'can update and delete snippets', 2, 1770141720);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS roles;
-- +goose StatementEnd
