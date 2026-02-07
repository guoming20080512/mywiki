import {
  EditorMarkdown,
  MarkdownEditorRef,
  UseTiptapReturn,
} from '@ctzhian/tiptap';
import { Box } from '@mui/material';
import { forwardRef } from 'react';

interface MarkdownEditorProps {
  editor: UseTiptapReturn['editor'];
  value: string;
  onChange: (value: string) => void;
  header: React.ReactNode;
}

const MarkdownEditor = forwardRef<MarkdownEditorRef, MarkdownEditorProps>(
  ({ editor, value, onChange, header }, ref) => {
    return (
      <Box
        sx={{
          mt: '56px',
          px: 10,
          pt: 4,
          flex: 1,
        }}
      >
        <Box sx={{}}>{header}</Box>
        <EditorMarkdown
          editor={editor}
          value={value}
          onAceChange={onChange}
          height='calc(100vh - 340px)'
        />
      </Box>
    );
  },
);

MarkdownEditor.displayName = 'MarkdownEditor';

export default MarkdownEditor;
