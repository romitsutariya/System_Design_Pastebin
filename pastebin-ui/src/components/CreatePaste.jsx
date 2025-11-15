import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  Box,
  Container,
  Typography,
  TextField,
  MenuItem,
  Select,
  InputLabel,
  FormControl,
  Stack,
  Paper,
  Button,
} from '@mui/material';
import { api } from '../services/api';

const expirations = [
  { value: 'never', label: 'Never' },
  { value: '10min', label: '10 minutes' },
  { value: '1hour', label: '1 hour' },
  { value: '1day', label: '1 day' },
  { value: '1week', label: '1 week' },
  { value: '1year', label: '1 year' },
];

const visibilities = [
  { value: 'public', label: 'Public' },
  { value: 'unlisted', label: 'Unlisted' },
  { value: 'private', label: 'Private' },
];

export default function CreatePaste() {
  const navigate = useNavigate();
  const location = useLocation();
  const [language, setLanguage] = useState('Python');
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [expiresAt, setExpiresAt] = useState('never');
  const [visibility, setVisibility] = useState('public');
  const [tags, setTags] = useState(''); // comma separated
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    // Require auth for creating a paste
    const token = (() => { try { return sessionStorage.getItem('jwt'); } catch { return null; } })();
    if (!token) {
      navigate('/login', { state: { from: location.pathname } });
      return;
    }
    const payload = {
      language,
      title,
      content,
      expiresAt,
      visibility,
      tags: tags
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean),
      createdAt: new Date().toISOString(),
    };
    try {
      const created = await api.createPaste(payload);
      if (created?.id) {
        navigate(`/pastes/${created.id}`);
      } else {
        navigate('/view', { state: { paste: created || payload } });
      }
    } catch (err) {
      console.error('Failed to create paste:', err);
      // Fallback to client-side view so the UI flow still works without backend
      navigate('/view', { state: { paste: payload } });
    }
  };

  return (
    <Container maxWidth="lg" sx={{ py: { xs: 2, md: 4 }, minHeight: '100vh' }}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
        <Typography variant="h4" fontWeight={700}>New Paste</Typography>
        <Typography variant="body1" color="text.secondary">{language}</Typography>
      </Stack>

      <Box component="form" onSubmit={handleSubmit} noValidate>
        <Paper variant="outlined" sx={{ p: { xs: 1.5, md: 2 }, mb: 3 }}>
          <TextField
            label="Your code or text"
            placeholder={'def something:\n    print("hello world")'}
            value={content}
            onChange={(e) => setContent(e.target.value)}
            multiline
            minRows={10}
            fullWidth
          />
        </Paper>

        <Paper variant="outlined" sx={{ p: { xs: 1.5, md: 2 } }}>
          <Stack spacing={2}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }}>
              <Typography width={{ sm: 140 }}>Title</Typography>
              <TextField
                fullWidth
                placeholder="My Paste"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />
            </Stack>

            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }}>
              <Typography width={{ sm: 140 }}>Expires At</Typography>
              <FormControl fullWidth>
                <InputLabel id="exp-label">Expires At</InputLabel>
                <Select
                  labelId="exp-label"
                  label="Expires At"
                  value={expiresAt}
                  onChange={(e) => setExpiresAt(e.target.value)}
                >
                  {expirations.map((opt) => (
                    <MenuItem key={opt.value} value={opt.value}>{opt.label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Stack>

            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }}>
              <Typography width={{ sm: 140 }}>Visibility</Typography>
              <FormControl fullWidth>
                <InputLabel id="vis-label">Visibility</InputLabel>
                <Select
                  labelId="vis-label"
                  label="Visibility"
                  value={visibility}
                  onChange={(e) => setVisibility(e.target.value)}
                >
                  {visibilities.map((opt) => (
                    <MenuItem key={opt.value} value={opt.value}>{opt.label}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Stack>

            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }}>
              <Typography width={{ sm: 140 }}>Tags</Typography>
              <TextField
                fullWidth
                placeholder="leetcode, algo"
                helperText="Comma-separated"
                value={tags}
                onChange={(e) => setTags(e.target.value)}
              />
            </Stack>

            <Stack direction="row" justifyContent="flex-end" pt={1}>
              <Button type="submit" variant="contained">Create Paste</Button>
            </Stack>
          </Stack>
        </Paper>
      </Box>
    </Container>
  );
}
