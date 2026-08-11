BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "player" ALTER COLUMN "regionX" DROP NOT NULL;
ALTER TABLE "player" ALTER COLUMN "regionY" DROP NOT NULL;
ALTER TABLE "player" ALTER COLUMN "regionWidth" DROP NOT NULL;
ALTER TABLE "player" ALTER COLUMN "regionHeight" DROP NOT NULL;

--
-- MIGRATION VERSION FOR draw_together_serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('draw_together_serverpod', '20260811072609391', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260811072609391', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260129181124635', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129181124635', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260129181112269', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129181112269', "timestamp" = now();


COMMIT;
