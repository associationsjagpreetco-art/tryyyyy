import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title:'ClinicRemind — Clinic operations, made calmer', description:'Appointment booking, patient follow-ups and simulated WhatsApp reminders for clinics.' };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body>{children}</body></html>; }
