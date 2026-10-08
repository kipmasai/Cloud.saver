import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;
export const isSupabaseConfigured = Boolean(url && key && !url.includes('YOUR_PROJECT_REF') && !key.includes('YOUR_'));
export const supabase = isSupabaseConfigured ? createClient(url!, key!, {
  auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true },
}) : null;

export type Profile = { id: string; display_name: string | null; first_name: string | null; last_name: string | null; phone: string | null; avatar_url: string | null; created_at: string };
export type CloudFile = { id: string; owner_id: string; name: string; storage_path: string; mime_type: string; size_bytes: number; category: string; created_at: string; updated_at: string; deleted_at: string | null; is_shared: boolean };
export const formatBytes = (bytes: number) => {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B';
  const units = ['B','KB','MB','GB','TB']; const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
};
export const fileCategory = (file: File | Pick<CloudFile, 'mime_type' | 'name'>) => {
  const type = ('type' in file ? file.type : file.mime_type) || ''; const name = file.name.toLowerCase();
  if (type.startsWith('image/')) return 'images'; if (type.startsWith('video/')) return 'videos'; if (type.startsWith('audio/')) return 'audio';
  if (type === 'application/pdf' || /\.(docx?|xlsx?|pptx?|txt|csv|odt|rtf)$/.test(name)) return 'documents';
  return 'other';
};
