BEGIN TRANSACTION;

ALTER TABLE container_auth
ADD COLUMN token CHAR(32) NOT NULL UNIQUE;

COMMIT TRANSACTION;

