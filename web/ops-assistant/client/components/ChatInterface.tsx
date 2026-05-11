import React from 'react';
const ChatInterface: React.FC = () => {
  // Chat interface is now provided by CopilotSidebar in App.tsx
  // This component is kept for backward compatibility but renders minimal content

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        backgroundColor: '#fff'
      }}
    >


        <p>Chat interface is managed by CopilotSidebar</p>
    </div>
  );
};

export default ChatInterface;
