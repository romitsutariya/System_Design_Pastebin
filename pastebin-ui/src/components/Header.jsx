import { Link as RouterLink, useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import Button from '@mui/material/Button';
import Box from '@mui/material/Box';
import Container from '@mui/material/Container';

export default function Header() {
  const navigate = useNavigate();
  const [authed, setAuthed] = useState(() => {
    try { return Boolean(sessionStorage.getItem('jwt')); } catch { return false; }
  });

  useEffect(() => {
    const onStorage = () => {
      try { setAuthed(Boolean(sessionStorage.getItem('jwt'))); } catch { setAuthed(false); }
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  const handleLogout = () => {
    try { sessionStorage.removeItem('jwt'); } catch {}
    setAuthed(false);
    navigate('/');
  };

  return (
    <AppBar position="sticky" color="primary" elevation={2} sx={{ mb: 10, left: 0, right: 0, width: '100%' }}>
      <Container maxWidth="lg">
      <Toolbar>
        <Typography
          variant="h6"
          sx={{ flexGrow: 1, fontWeight: 700, textDecoration: 'none' }}
          component={RouterLink}
          to="/"
          color="white"
        >
          Pastebin
        </Typography>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Button component={RouterLink} to="/" variant="text" color="white">
            Create Paste
          </Button>
          {authed ? (
            <Button onClick={handleLogout} variant="text" color="white">
              Logout
            </Button>
          ) : (
            <>
              <Button component={RouterLink} to="/login" variant="text" color="white">
                Login
              </Button>
              <Button component={RouterLink} to="/register" variant="text" color="white">
                Register
              </Button>
            </>
          )}
        </Box>
      </Toolbar>
      </Container>
    </AppBar>
  );
}
