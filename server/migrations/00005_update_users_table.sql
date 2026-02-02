-- +goose Up
-- +goose StatementBegin
ALTER TABLE users
ADD role_id bigint not null default 1 references roles(id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE users drop column role_id;
-- +goose StatementEnd
