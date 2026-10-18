export type MessageInput = { to:string; body:string; type:string };
export type ProviderResult = { provider:string; status:'SIMULATED'|'SENT'|'FAILED'; externalId?:string };
export interface WhatsAppProvider { send(input:MessageInput):Promise<ProviderResult> }
/** Safe default: records a simulation, never claims a WhatsApp message was delivered. */
export class MockProvider implements WhatsAppProvider { async send(_input:MessageInput):Promise<ProviderResult>{ return {provider:'MockProvider',status:'SIMULATED'}; } }
/** Integration seam only. Add Meta Graph API calls, template mapping, webhook verification and retry policy before enabling. */
export class WhatsAppCloudProvider implements WhatsAppProvider { async send(_input:MessageInput):Promise<ProviderResult>{ if(!process.env.WHATSAPP_ACCESS_TOKEN || !process.env.WHATSAPP_PHONE_NUMBER_ID) throw new Error('Meta WhatsApp credentials are not configured'); throw new Error('Cloud API transport is an integration stub; no message was sent'); } }
export function getWhatsAppProvider():WhatsAppProvider { return process.env.WHATSAPP_PROVIDER==='cloud' ? new WhatsAppCloudProvider() : new MockProvider(); }
