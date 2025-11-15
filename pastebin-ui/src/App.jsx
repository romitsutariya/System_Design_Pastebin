import { Routes, Route, Navigate } from 'react-router-dom';
import CreatePaste from './components/CreatePaste';
import ViewPaste from './components/ViewPaste';
import Login from './components/Login';
import Header from './components/Header';
import Register from './components/Register';

function App() {
  return (
    <>
      <Header />
      <Routes>
        <Route path="/" element={<CreatePaste />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/pastes/:id" element={<ViewPaste />} />
        <Route path="/view" element={<ViewPaste />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  );
}

export default App
