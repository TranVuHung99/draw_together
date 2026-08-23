BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "stroke" (
    "id" bigserial PRIMARY KEY,
    "roomId" bigint NOT NULL,
    "playerId" bigint NOT NULL,
    "strokeId" text NOT NULL,
    "points" json NOT NULL,
    "colorInfo" text NOT NULL,
    "strokeWidth" double precision NOT NULL,
    "isEraser" boolean NOT NULL,
    "sequence" bigint NOT NULL,
    "timestamp" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "stroke_room_seq_idx" ON "stroke" USING btree ("roomId", "sequence");


--
-- MIGRATION VERSION FOR draw_together_serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('draw_together_serverpod', '20260821150802524', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260821150802524', "timestamp" = now();

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
