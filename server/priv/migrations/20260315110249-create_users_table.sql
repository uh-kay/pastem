--- migration:up
CREATE TABLE if not exists users (
    id bigserial primary key,
    username varchar(255) unique not null,
    email citext unique not null,
    password_hash text not null,
    created_at bigint not null
);
--- migration:down
drop table if exists users;
--- migration:end
