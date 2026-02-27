-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS sessions (
    id uuid primary key,
    user_id bigint not null references users(id) on delete cascade,
    expires_at bigint not null
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS sessions;
-- +goose StatementEnd
