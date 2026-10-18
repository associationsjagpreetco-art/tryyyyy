CREATE TABLE "Clinic" (
  "id" TEXT NOT NULL, "slug" TEXT NOT NULL, "name" TEXT NOT NULL, "accent" TEXT NOT NULL,
  "doctorName" TEXT NOT NULL DEFAULT 'Clinic doctor', "phone" TEXT NOT NULL, "address" TEXT NOT NULL,
  "language" TEXT NOT NULL DEFAULT 'en', "slotMinutes" INTEGER NOT NULL DEFAULT 20,
  "openingTime" TEXT NOT NULL DEFAULT '09:00', "closingTime" TEXT NOT NULL DEFAULT '18:00',
  "workingDays" TEXT NOT NULL DEFAULT '1,2,3,4,5,6', "modules" TEXT NOT NULL DEFAULT 'appointments,followups',
  "isDemo" BOOLEAN NOT NULL DEFAULT true, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL, CONSTRAINT "Clinic_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "Patient" (
  "id" TEXT NOT NULL, "clinicId" TEXT NOT NULL, "name" TEXT NOT NULL, "phone" TEXT NOT NULL,
  "reason" TEXT, "notes" TEXT, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Patient_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "Appointment" (
  "id" TEXT NOT NULL, "clinicId" TEXT NOT NULL, "patientId" TEXT NOT NULL, "startsAt" TIMESTAMP(3) NOT NULL,
  "duration" INTEGER NOT NULL DEFAULT 20, "reason" TEXT, "status" TEXT NOT NULL DEFAULT 'BOOKED',
  "source" TEXT NOT NULL DEFAULT 'STAFF', "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL, CONSTRAINT "Appointment_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "FollowUp" (
  "id" TEXT NOT NULL, "clinicId" TEXT NOT NULL, "patientId" TEXT NOT NULL, "dueAt" TIMESTAMP(3) NOT NULL,
  "note" TEXT NOT NULL, "status" TEXT NOT NULL DEFAULT 'DUE', "completedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "FollowUp_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "OpticalOrder" (
  "id" TEXT NOT NULL, "clinicId" TEXT NOT NULL, "patientId" TEXT NOT NULL, "frame" TEXT NOT NULL,
  "lens" TEXT NOT NULL, "prescriptionNote" TEXT, "advance" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "total" DOUBLE PRECISION NOT NULL DEFAULT 0, "status" TEXT NOT NULL DEFAULT 'ORDERED', "readyAt" TIMESTAMP(3),
  "collectedAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL, CONSTRAINT "OpticalOrder_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "Message" (
  "id" TEXT NOT NULL, "clinicId" TEXT NOT NULL, "patientId" TEXT NOT NULL, "appointmentId" TEXT,
  "type" TEXT NOT NULL, "status" TEXT NOT NULL DEFAULT 'SIMULATED', "body" TEXT NOT NULL,
  "provider" TEXT NOT NULL DEFAULT 'MockProvider', "sentAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "reply" TEXT, CONSTRAINT "Message_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "MessageTemplate" (
  "id" TEXT NOT NULL, "clinicId" TEXT NOT NULL, "language" TEXT NOT NULL, "type" TEXT NOT NULL,
  "body" TEXT NOT NULL, CONSTRAINT "MessageTemplate_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "Clinic_slug_key" ON "Clinic"("slug");
CREATE UNIQUE INDEX "Patient_clinicId_phone_key" ON "Patient"("clinicId", "phone");
CREATE INDEX "Patient_clinicId_name_idx" ON "Patient"("clinicId", "name");
CREATE INDEX "Appointment_clinicId_startsAt_idx" ON "Appointment"("clinicId", "startsAt");
CREATE INDEX "FollowUp_clinicId_dueAt_status_idx" ON "FollowUp"("clinicId", "dueAt", "status");
CREATE INDEX "Message_clinicId_sentAt_idx" ON "Message"("clinicId", "sentAt");
CREATE UNIQUE INDEX "MessageTemplate_clinicId_language_type_key" ON "MessageTemplate"("clinicId", "language", "type");
ALTER TABLE "Patient" ADD CONSTRAINT "Patient_clinicId_fkey" FOREIGN KEY ("clinicId") REFERENCES "Clinic"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_clinicId_fkey" FOREIGN KEY ("clinicId") REFERENCES "Clinic"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FollowUp" ADD CONSTRAINT "FollowUp_clinicId_fkey" FOREIGN KEY ("clinicId") REFERENCES "Clinic"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FollowUp" ADD CONSTRAINT "FollowUp_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OpticalOrder" ADD CONSTRAINT "OpticalOrder_clinicId_fkey" FOREIGN KEY ("clinicId") REFERENCES "Clinic"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OpticalOrder" ADD CONSTRAINT "OpticalOrder_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Message" ADD CONSTRAINT "Message_clinicId_fkey" FOREIGN KEY ("clinicId") REFERENCES "Clinic"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Message" ADD CONSTRAINT "Message_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Message" ADD CONSTRAINT "Message_appointmentId_fkey" FOREIGN KEY ("appointmentId") REFERENCES "Appointment"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "MessageTemplate" ADD CONSTRAINT "MessageTemplate_clinicId_fkey" FOREIGN KEY ("clinicId") REFERENCES "Clinic"("id") ON DELETE CASCADE ON UPDATE CASCADE;
-- Serialize booking checks per clinic so concurrent requests cannot reserve overlapping slots.
CREATE OR REPLACE FUNCTION clinicremind_prevent_overlap() RETURNS TRIGGER AS $$
BEGIN
  PERFORM 1 FROM "Clinic" WHERE "id" = NEW."clinicId" FOR UPDATE;
  IF NEW."status" NOT IN ('CANCELLED', 'NO_SHOW') AND EXISTS (
    SELECT 1 FROM "Appointment" a
    WHERE a."clinicId" = NEW."clinicId" AND a."id" <> COALESCE(NEW."id", '')
      AND a."status" NOT IN ('CANCELLED', 'NO_SHOW')
      AND NEW."startsAt" < a."startsAt" + (a."duration" * INTERVAL '1 minute')
      AND a."startsAt" < NEW."startsAt" + (NEW."duration" * INTERVAL '1 minute')
  ) THEN RAISE EXCEPTION 'APPOINTMENT_SLOT_CONFLICT' USING ERRCODE = '23P01'; END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER "Appointment_prevent_overlap" BEFORE INSERT OR UPDATE OF "clinicId", "startsAt", "duration", "status" ON "Appointment"
FOR EACH ROW EXECUTE FUNCTION clinicremind_prevent_overlap();
