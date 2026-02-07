import { ITreeItem } from '@/api';
import Card from '@/components/Card';
import DragTree from '@/components/Drag/DragTree';
import { postApiV1NodeBatchMove } from '@/request/Node';
import { DomainNodeListItemResp } from '@/request/types';
import { useAppSelector } from '@/store';
import { convertToTree } from '@/utils/drag';
import { message, Modal } from '@ctzhian/ui';
import { Box, Checkbox, Stack } from '@mui/material';
import { useEffect, useState } from 'react';
import { IconWenjianjiaKai } from '@panda-wiki/icons';

interface DocDeleteProps {
  open: boolean;
  onClose: () => void;
  data: DomainNodeListItemResp[];
  selected: DomainNodeListItemResp[];
  onMoved?: (payload: { ids: string[]; parentId: string }) => void;
}

const MoveDocs = ({
  open,
  onClose,
  data,
  selected,
  onMoved,
}: DocDeleteProps) => {
  const { kb_id } = useAppSelector(state => state.config);
  const [tree, setTree] = useState<ITreeItem[]>([]);
  const [folderIds, setFolderIds] = useState<string[]>([]);

  const handleOk = () => {
    if (folderIds.length === 0) {
      message.error('请选择移动路径');
      return;
    }
    const ids = selected.filter(it => it.type === 1).map(it => it.id!);
    selected
      .filter(it => it.type === 2)
      .forEach(it => {
        if (!ids.includes(it.parent_id!)) {
          ids.push(it.id!);
        }
      });
    const parent_id = folderIds.includes('root') ? '' : folderIds[0];
    postApiV1NodeBatchMove({ ids, parent_id, kb_id }).then(() => {
      message.success('移动成功');
      onClose();
      onMoved?.({ ids, parentId: parent_id });
    });
  };

  useEffect(() => {
    if (open && selected.length > 0) {
      const folder = selected.filter(it => it.type === 1).map(it => it.id);
      const filterData = data.filter(
        it => it.type === 1 && !folder.includes(it.id),
      );
      setTree(convertToTree(filterData));
    }
  }, [open, data, selected]);

  return (
    <Modal title='移动文档' open={open} onCancel={onClose} onOk={handleOk}>
      <Box sx={{ fontSize: 14, mb: 1, color: 'text.secondary' }}>
        已选中
        <Box component={'span'} sx={{ fontWeight: 700, color: 'primary.main' }}>
          {' '}
          {selected.length}{' '}
        </Box>
        个文档/文件夹，移动到
      </Box>
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
          <IconWenjianjiaKai sx={{ fontSize: 14 }} />
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

export default MoveDocs;
