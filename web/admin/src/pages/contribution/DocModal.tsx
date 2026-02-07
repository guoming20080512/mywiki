import { ITreeItem } from '@/api';
import Card from '@/components/Card';
import DragTree from '@/components/Drag/DragTree';
import { useAppSelector } from '@/store';
import { convertToTree } from '@/utils/drag';
import { Box, Checkbox, Stack } from '@mui/material';
import { Modal } from '@ctzhian/ui';
import { useEffect, useState } from 'react';
import { getApiV1NodeList } from '@/request/Node';
import { IconWenjianjiaKai } from '@panda-wiki/icons';

interface DocDeleteProps {
  open: boolean;
  onClose: () => void;
  onOk: (id: string) => void;
}

const DocModal = ({ open, onClose, onOk }: DocDeleteProps) => {
  const { kb_id } = useAppSelector(state => state.config);
  const [tree, setTree] = useState<ITreeItem[]>([]);
  const [folderIds, setFolderIds] = useState<string[]>([]);

  const handleOk = () => {
    onOk(folderIds.includes('root') ? '' : folderIds[0]);
  };

  useEffect(() => {
    if (open) {
      getApiV1NodeList({ kb_id }).then(res => {
        const folder = res.filter(it => it.type === 1);
        setTree(convertToTree(folder));
      });
    }
  }, [open]);

  return (
    <Modal title='选择目录' open={open} onCancel={onClose} onOk={handleOk}>
      <Card sx={{ bgcolor: 'background.paper3', p: 1 }}>
        <Stack
          direction={'row'}
          alignItems={'center'}
          gap={1}
          sx={{ fontSize: 14, cursor: 'pointer' }}
        >
          <Checkbox
            sx={{ color: 'text.disabled', width: '35px', height: '35px' }}
            checked={folderIds.includes('root')}
            onChange={() => {
              setFolderIds(folderIds.includes('root') ? [] : ['root']);
            }}
          />
          <IconWenjianjiaKai sx={{ fontSize: 16 }} />
          <Box>根路径</Box>
        </Stack>
        <DragTree
          ui='select'
          selected={folderIds}
          data={tree}
          readOnly={true}
          relativeSelect={false}
          onSelectChange={(ids, id = '') => {
            if (folderIds.includes(id)) {
              setFolderIds([]);
            } else {
              setFolderIds([id]);
            }
          }}
        />
      </Card>
    </Modal>
  );
};

export default DocModal;
