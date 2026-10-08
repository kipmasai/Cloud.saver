import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from 'https://deno.land/x/cors@v1.2.2/mod.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  try {
    const { token } = await req.json();
    if (typeof token !== 'string' || !/^[a-f0-9]{48}$/.test(token)) return new Response(JSON.stringify({ error: 'Invalid share link' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !serviceKey) throw new Error('Server storage credentials are not configured');
    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: share, error: shareError } = await admin.from('file_shares').select('file_id, expires_at, revoked_at').eq('token', token).maybeSingle();
    if (shareError || !share || share.revoked_at || (share.expires_at && new Date(share.expires_at) <= new Date())) return new Response(JSON.stringify({ error: 'This share link is invalid, expired, or revoked.' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    const { data: file, error: fileError } = await admin.from('cloud_files').select('id, name, storage_path, mime_type, size_bytes, deleted_at').eq('id', share.file_id).maybeSingle();
    if (fileError || !file || file.deleted_at) return new Response(JSON.stringify({ error: 'This file is no longer available.' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    const { data: signed, error: signedError } = await admin.storage.from('cloud-files').createSignedUrl(file.storage_path, 60, { download: file.name });
    if (signedError || !signed?.signedUrl) throw new Error('Could not create a temporary download link');
    return new Response(JSON.stringify({ file: { name: file.name, mime_type: file.mime_type, size_bytes: file.size_bytes }, signedUrl: signed.signedUrl }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error';
    return new Response(JSON.stringify({ error: message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
  }
});
