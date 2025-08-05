#!/bin/bash

# Go to root and create frontend
cd mern-crud-auth
npm create vite@latest frontend -- --template react
cd frontend

# Install dependencies
npm install axios react-router-dom

# Create folders
mkdir src/pages src/components src/context

# Create .env file for frontend
cat <<EOF > .env
VITE_API_URL=http://localhost:5000
EOF

# Add AuthContext
cat <<EOF > src/context/AuthContext.jsx
import { createContext, useState, useEffect } from 'react';

export const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);

  useEffect(() => {
    const stored = localStorage.getItem('user');
    if (stored) setUser(JSON.parse(stored));
  }, []);

  const login = (data) => {
    setUser(data);
    localStorage.setItem('user', JSON.stringify(data));
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem('user');
  };

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};
EOF

cat <<EOF > src/axios.js
import axios from 'axios';

const instance = axios.create({
  baseURL: import.meta.env.VITE_API_URL
});

export default instance;
EOF


# Add Login Page
cat <<EOF > src/pages/Login.jsx
import { useState, useContext } from 'react';
import axios from 'axios';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login } = useContext(AuthContext);
  const navigate = useNavigate();

  const handleLogin = async () => {
    try {
      const res = await axios.post('http://localhost:5000/api/auth/login', { email, password });
      login(res.data);
      navigate('/items');
    } catch (err) {
      alert('Login failed');
    }
  };

  return (
    <div>
      <h2>Login</h2>
      <input value={email} onChange={e => setEmail(e.target.value)} placeholder="Email" />
      <input value={password} onChange={e => setPassword(e.target.value)} placeholder="Password" type="password" />
      <button onClick={handleLogin}>Login</button>
    </div>
  );
}
EOF

# Add Signup Page
cat <<EOF > src/pages/Signup.jsx
import { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

export default function Signup() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const navigate = useNavigate();

  const handleSignup = async () => {
    try {
      await axios.post('http://localhost:5000/api/auth/register', { name, email, password });
      navigate('/login');
    } catch (err) {
      alert('Signup failed');
    }
  };

  return (
    <div>
      <h2>Signup</h2>
      <input value={name} onChange={e => setName(e.target.value)} placeholder="Name" />
      <input value={email} onChange={e => setEmail(e.target.value)} placeholder="Email" />
      <input value={password} onChange={e => setPassword(e.target.value)} placeholder="Password" type="password" />
      <button onClick={handleSignup}>Signup</button>
    </div>
  );
}
EOF

# Add Items Page
cat <<EOF > src/pages/Items.jsx
import { useState, useEffect, useContext } from 'react';
import axios from 'axios';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Items() {
  const [items, setItems] = useState([]);
  const [title, setTitle] = useState('');
  const [desc, setDesc] = useState('');
  const { user, logout } = useContext(AuthContext);
  const navigate = useNavigate();

  const fetchItems = async () => {
    const res = await axios.get('http://localhost:5000/api/items', {
      headers: { Authorization: `Bearer ${user.token}` }
    });
    setItems(res.data);
  };

  useEffect(() => {
    if (!user) return navigate('/login');
    fetchItems();
  }, []);

  const addItem = async () => {
    await axios.post('http://localhost:5000/api/items', {
      title, description: desc
    }, {
      headers: { Authorization: `Bearer ${user.token}` }
    });
    setTitle('');
    setDesc('');
    fetchItems();
  };

  const deleteItem = async (id) => {
    await axios.delete(\`http://localhost:5000/api/items/\${id}\`, {
      headers: { Authorization: \`Bearer \${user.token}\` }
    });
    fetchItems();
  };

  return (
    <div>
      <h2>Welcome {user.user.name}</h2>
      <button onClick={() => { logout(); navigate('/login'); }}>Logout</button>
      <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Title" />
      <input value={desc} onChange={e => setDesc(e.target.value)} placeholder="Description" />
      <button onClick={addItem}>Add</button>
      <ul>
        {items.map(i => (
          <li key={i._id}>
            {i.title} - {i.description}
            <button onClick={() => deleteItem(i._id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
EOF

# Update App.jsx
cat <<EOF > src/App.jsx
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Login from './pages/Login';
import Signup from './pages/Signup';
import Items from './pages/Items';
import { AuthProvider } from './context/AuthContext';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Signup />} />
          <Route path="/login" element={<Login />} />
          <Route path="/items" element={<Items />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
EOF

echo "✅ Frontend setup complete. Run 'cd frontend && npm run dev'"
