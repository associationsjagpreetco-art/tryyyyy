import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getWhatsAppProvider } from '@/lib/provider';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/** Scheduler-compatible endpoint. All created messages are explicitly SIMULATED with MockProvider. */
export async function GET(req: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret || req.headers.get('authorization') !== `Bearer ${secret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const now = new Date();
  const windows = [
    { type: 'reminder24', start: new Date(now.getTime() + 23.75 * 60 * 60 * 1000), end: new Date(now.getTime() + 24 * 60 * 60 * 1000) },
    { type: 'reminder1', start: new Date(now.getTime() + 45 * 60 * 1000), end: new Date(now.getTime() + 60 * 60 * 1000) },
  ];
  let created = 0;
  const provider = getWhatsAppProvider();

  try {
    for (const window of windows) {
      const appointments = await prisma.appointment.findMany({
        where: { startsAt: { gte: window.start, lt: window.end }, status: { notIn: ['CANCELLED', 'NO_SHOW', 'COMPLETED'] } },
        include: { patient: true, clinic: true },
      });
      for (const appointment of appointments) {
        const exists = await prisma.message.findFirst({ where: { appointmentId: appointment.id, type: window.type } });
        if (exists) continue;
        const template = await prisma.messageTemplate.findUnique({ where: { clinicId_language_type: { clinicId: appointment.clinicId, language: appointment.clinic.language, type: window.type } } });
        const date = appointment.startsAt.toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata' });
        const time = appointment.startsAt.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Kolkata' });
        const link = `${process.env.NEXT_PUBLIC_APP_URL || ''}/book/${appointment.clinic.slug}`;
        const body = (template?.body || 'Reminder for {name} at {clinic} on {date}, {time}.')
          .replaceAll('{name}', appointment.patient.name).replaceAll('{clinic}', appointment.clinic.name)
          .replaceAll('{date}', date).replaceAll('{time}', time).replaceAll('{link}', link)
          .replaceAll('{hours}', `${appointment.clinic.openingTime}–${appointment.clinic.closingTime}`);
        const result = await provider.send({ to: appointment.patient.phone, body, type: window.type });
        await prisma.message.create({ data: { clinicId: appointment.clinicId, patientId: appointment.patientId, appointmentId: appointment.id, type: window.type, body, provider: result.provider, status: result.status } });
        created++;
      }
    }
    return NextResponse.json({ ok: true, created, mode: process.env.WHATSAPP_PROVIDER === 'cloud' ? 'cloud-stub' : 'simulation', notice: 'Mock messages are logged as SIMULATED and are not delivered.' });
  } catch (error) {
    console.error('Reminder cron failed', error);
    return NextResponse.json({ error: 'Reminder job failed' }, { status: 500 });
  }
}
