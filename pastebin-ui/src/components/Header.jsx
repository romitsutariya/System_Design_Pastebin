import { Link as RouterLink, useNavigate, useLocation } from 'react-router-dom';
import { useEffect, useState } from 'react';
import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import Button from '@mui/material/Button';
import Box from '@mui/material/Box';
import Container from '@mui/material/Container';

export default function Header() {
  const navigate = useNavigate();
  const location = useLocation();
  const parseJwt = (token) => {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(atob(base64).split('').map(c => '%'+('00'+c.charCodeAt(0).toString(16)).slice(-2)).join(''));
      return JSON.parse(jsonPayload);
    } catch {
      return null;
    }
  };

  const getUsernameFromStorage = () => {
    try {
      const t = sessionStorage.getItem('jwt');
      if (!t) return null;
      const payload = parseJwt(t);
      return payload?.user_id || null;
    } catch {
      return null;
    }
  };

  const [authed, setAuthed] = useState(() => {
    try { return Boolean(sessionStorage.getItem('jwt')); } catch { return false; }
  });
  const [username, setUsername] = useState(() => getUsernameFromStorage());

  useEffect(() => {
    const onStorage = () => {
      try {
        const hasToken = Boolean(sessionStorage.getItem('jwt'));
        setAuthed(hasToken);
        setUsername(getUsernameFromStorage());
      } catch {
        setAuthed(false);
        setUsername(null);
      }
    };
    window.addEventListener('storage', onStorage);
    window.addEventListener('focus', onStorage);
    return () => {
      window.removeEventListener('storage', onStorage);
      window.removeEventListener('focus', onStorage);
    };
  }, []);

  // Recompute auth state on route changes (same-tab updates after login/register)
  useEffect(() => {
    try {
      const hasToken = Boolean(sessionStorage.getItem('jwt'));
      setAuthed(hasToken);
      setUsername(getUsernameFromStorage());
    } catch {
      setAuthed(false);
      setUsername(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname]);

  const handleLogout = () => {
    try { sessionStorage.removeItem('jwt'); } catch {}
    setAuthed(false);
    setUsername(null);
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
            <>
              <Typography variant="body2" color="white" sx={{ alignSelf: 'center', mr: 1 }}>
                {username ? `Hello, ${username}` : 'Signed in'}
              </Typography>
              <Button onClick={handleLogout} variant="text" color="white">
                Logout
              </Button>
            </>
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
