import { Routes, Route, Navigate } from 'react-router-dom';
import CreatePaste from './components/CreatePaste';
import ViewPaste from './components/ViewPaste';

function App() {
  return (
    <Routes>
      <Route path="/" element={<CreatePaste />} />
      <Route path="/pastes/:id" element={<ViewPaste />} />
      <Route path="/view" element={<ViewPaste />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default App
