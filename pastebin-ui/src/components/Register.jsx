import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  Box,
  Button,
  Container,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { api } from '../services/api';

export default function Register() {
  const navigate = useNavigate();
  const location = useLocation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const redirectTo = location.state?.from || '/';

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const data = await api.register({ username, password });
      if (data?.token) {
        sessionStorage.setItem('jwt', data.token);
        navigate(redirectTo, { replace: true });
      } else {
        setError('Registration failed');
      }
    } catch (err) {
      setError(err?.message || 'Registration failed');
    }
  };

  return (
    <Container maxWidth="xs" sx={{ py: 8 }}>
      <Paper variant="outlined" sx={{ p: 3 }}>
        <Typography variant="h5" fontWeight={700} gutterBottom>Create account</Typography>
        {error ? (
          <Typography color="error" variant="body2" sx={{ mb: 2 }}>{error}</Typography>
        ) : null}
        <Box component="form" onSubmit={handleSubmit}>
          <Stack spacing={2}>
            <TextField
              label="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoFocus
              required
              fullWidth
            />
            <TextField
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              fullWidth
            />
            <Button type="submit" variant="contained">Register</Button>
          </Stack>
        </Box>
      </Paper>
    </Container>
  );
}
