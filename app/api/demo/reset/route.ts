import { NextResponse } from 'next/server'; import { spawn } from 'node:child_process';
export async function POST(){return NextResponse.json({error:'Use npm run db:reset-demo after stopping the dev server to reseed the demo database. This endpoint intentionally does not execute shell commands.'},{status:501})}
