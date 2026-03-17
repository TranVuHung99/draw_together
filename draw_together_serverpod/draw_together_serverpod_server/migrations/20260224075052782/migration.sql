BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "player" (
    "id" bigserial PRIMARY KEY,
    "roomId" bigint NOT NULL,
    "roomId" bigint NOT NULL,
    "name" text NOT NULL,
    "colorInfo" text,
    "regionX" double precision NOT NULL,
    "regionY" double precision NOT NULL,
    "regionWidth" double precision NOT NULL,
    "regionHeight" double precision NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "room" (
    "id" bigserial PRIMARY KEY,
    "roomCode" text NOT NULL,
    "hostId" bigint NOT NULL,
    "status" text NOT NULL,
    "canvasWidth" double precision NOT NULL,
    "canvasHeight" double precision NOT NULL,
    "endTime" timestamp without time zone
);

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "player"
    ADD CONSTRAINT "player_fk_0"
    FOREIGN KEY("roomId")
    REFERENCES "room"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR draw_together_serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('draw_together_serverpod', '20260224075052782', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260224075052782', "timestamp" = now();

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
