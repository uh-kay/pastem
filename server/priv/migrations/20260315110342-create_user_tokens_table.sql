--- migration:up
CREATE TABLE IF NOT EXISTS user_tokens (
    hash bytea PRIMARY KEY,
    user_id bigint not null references users(id) on delete cascade,
    expiry bigint not null,
    scope text not null
);
--- migration:down
DROP TABLE IF EXISTS user_tokens;
--- migration:end
