import React, { useImperativeHandle, Ref } from 'react';
import { Box, Stack, FormControlLabel, Checkbox } from '@mui/material';
import importDoc from '@/assets/images/init/import.png';
import { postApiV1Node } from '@/request/Node';
import { INIT_DOC_DATA } from './initData';
import { useAppSelector } from '@/store';

interface Step3ImportProps {
  ref: Ref<{ onSubmit: () => Promise<Record<'id', string>[]> }>;
}

const Step3Import: React.FC<Step3ImportProps> = ({ ref }) => {
  const { kb_id } = useAppSelector(state => state.config);
  const onSubmit = () => {
    return Promise.all(
      INIT_DOC_DATA.map(item => {
        return postApiV1Node({
          ...item,
          kb_id,
        });
      }),
    );
  };

  useImperativeHandle(ref, () => ({
    onSubmit,
  }));

  return (
    <Stack gap={2} sx={{ textAlign: 'center', py: 4 }}>
      <Box component='img' src={importDoc} sx={{ width: '100%' }}></Box>
      <FormControlLabel
        control={
          <Checkbox
            checked
            sx={{ m: 1, color: 'rgba(50, 72, 242, 0.6) !important' }}
          />
        }
        label='导入样例文档'
      />
    </Stack>
  );
};

export default Step3Import;
