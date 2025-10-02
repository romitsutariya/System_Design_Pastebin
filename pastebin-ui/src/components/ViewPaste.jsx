import { useEffect, useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import {
  Box,
  Chip,
  Container,
  Paper,
  Stack,
  Typography,
  Button,
  Divider,
} from '@mui/material';
import { api } from '../services/api';

function normalizeTags(tags) {
  if (Array.isArray(tags)) return tags;
  if (typeof tags === 'string') {
    return tags.split(',').map((t) => t.trim()).filter(Boolean);
  }
  return [];
}

function formatExpires(value) {
  if (value == null || value === '' || value === 'never') return 'Never';
  // accept number (seconds), numeric string, or ISO string
  if (typeof value === 'number') {
    const date = new Date(value * 1000);
    return isNaN(date.getTime()) ? String(value) : date.toLocaleString();
  }
  if (/^\d+$/.test(value)) {
    const date = new Date(parseInt(value, 10) * 1000);
    return isNaN(date.getTime()) ? value : date.toLocaleString();
  }
  const date = new Date(value);
  return isNaN(date.getTime()) ? String(value) : date.toLocaleString();
}

export default function ViewPaste() {
  const navigate = useNavigate();
  const { state } = useLocation();
  const { id } = useParams();
  const [paste, setPaste] = useState(state?.paste || null);
  const [loading, setLoading] = useState(Boolean(id) && !state?.paste);
  const [error, setError] = useState('');

  useEffect(() => {
    let ignore = false;
    async function run() {
      if (!id || state?.paste) return;
      setLoading(true);
      try {
        const data = await api.getPaste(id);
        if (!ignore) setPaste({ ...data, tags: normalizeTags(data?.tags) });
      } catch (e) {
        if (!ignore) setError(e.message || 'Failed to load paste');
      } finally {
        if (!ignore) setLoading(false);
      }
    }
    run();
    return () => { ignore = true; };
  }, [id, state?.paste]);

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ py: 6 }}>
        <Typography>Loading paste...</Typography>
      </Container>
    );
  }

  if (error) {
    return (
      <Container maxWidth="lg" sx={{ py: 6 }}>
        <Typography color="error" gutterBottom>{error}</Typography>
        <Button variant="contained" onClick={() => navigate('/')}>Create a Paste</Button>
      </Container>
    );
  }

  if (!paste) {
    return (
      <Container maxWidth="lg" sx={{ py: 6 }}>
        <Typography variant="h5" gutterBottom>No paste data found</Typography>
        <Button variant="contained" onClick={() => navigate('/')}>Create a Paste</Button>
      </Container>
    );
  }

  // Normalize tags if coming from navigation state
  const tags = normalizeTags(paste?.tags);

  return (
    <Container maxWidth="lg" sx={{ py: { xs: 2, md: 4 }, minHeight: '100vh' }}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
        <Typography variant="h4" fontWeight={700}>{paste.title || 'Untitled Paste'}</Typography>
        <Typography variant="body1" color="text.secondary">{paste.language}</Typography>
      </Stack>

      <Paper variant="outlined" sx={{ p: { xs: 1.5, md: 2 }, mb: 3 }}>
        <Box component="pre" sx={{ whiteSpace: 'pre-wrap', m: 0, fontFamily: 'monospace' }}>
          {paste.content}
        </Box>
      </Paper>

      <Paper variant="outlined" sx={{ p: { xs: 1.5, md: 2 } }}>
        <Stack spacing={1}>
          <Typography variant="subtitle2" color="text.secondary">Details</Typography>
          <Divider />
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <Typography width={{ sm: 160 }}>Visibility</Typography>
            <Typography>{paste.visibility}</Typography>
          </Stack>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <Typography width={{ sm: 160 }}>Expires At</Typography>
            <Typography>{formatExpires(paste.expiresAt)}</Typography>
          </Stack>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <Typography width={{ sm: 160 }}>Tags</Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap">
              {tags.length ? tags.map((t, i) => (
                <Chip key={i} label={t} size="small" />
              )) : <Typography color="text.secondary">None</Typography>}
            </Stack>
          </Stack>
          <Stack direction="row" justifyContent="flex-end" pt={1}>
            <Button variant="outlined" onClick={() => navigate('/')}>Create another</Button>
          </Stack>
        </Stack>
      </Paper>
    </Container>
  );
}
