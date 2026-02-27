-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS auth_tokens (
    hash text PRIMARY KEY,
    user_id bigint not null references users(id) on delete cascade,
    expiry bigint not null
    -- scope text not null
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS auth_tokens;
-- +goose StatementEnd
